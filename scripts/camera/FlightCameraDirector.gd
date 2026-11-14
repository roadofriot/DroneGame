class_name FlightCameraDirector
extends Node3D

## FlightCameraDirector: Multi-camera manager supporting Chase, FPV, Orbit, and Top-Down.

enum CameraMode { CHASE, FPV, ORBIT, TOP_DOWN }

@export var target_drone: FlightPhysics
@export var chase_camera: Camera3D
@export var fpv_camera: Camera3D

# Chase camera tuning - calibrated for bold, prominent mobile framing
@export var chase_distance: float = 2.35
@export var chase_height: float = 0.85
@export var position_smooth_speed: float = 9.0
@export var rotation_smooth_speed: float = 14.0
@export var velocity_lookahead_factor: float = 0.22

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

func _compute_look_basis(from: Vector3, target: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var forward = target - from
	if forward.length_squared() < 0.0001:
		return Basis.IDENTITY
	forward = forward.normalized()
	var effective_up = up
	if abs(forward.dot(effective_up)) > 0.98:
		effective_up = Vector3.FORWARD if abs(forward.dot(Vector3.FORWARD)) < 0.98 else Vector3.RIGHT
	var right = forward.cross(effective_up).normalized()
	if right.length_squared() < 0.0001:
		return Basis.IDENTITY
	var final_up = right.cross(forward).normalized()
	# Godot Camera3D: -Z is camera look direction, +Y is camera up, +X is camera right
	return Basis(right, final_up, -forward).orthonormalized()

func _update_chase_camera(delta: float) -> void:
	if not chase_camera or not target_drone:
		return

	var drone_pos = target_drone.global_position
	if not drone_pos.is_finite():
		return
	var drone_basis = target_drone.global_transform.basis
	if not drone_basis.is_finite():
		return

	# Camera stays behind the drone along drone's horizontal facing direction
	var forward = -drone_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var target_cam_pos = drone_pos - (forward * chase_distance) + (Vector3.UP * chase_height)

	# Velocity lookahead
	var vel = target_drone.linear_velocity if target_drone.linear_velocity.is_finite() else Vector3.ZERO
	var vel_offset = vel * velocity_lookahead_factor
	var look_target = drone_pos + (forward * 0.8) + (vel_offset * 0.3)

	# Snap position on first frame or large teleports to prevent passing through target
	if not chase_camera.global_position.is_finite() or chase_camera.global_position.distance_squared_to(target_cam_pos) > 1000.0:
		chase_camera.global_position = target_cam_pos
	else:
		chase_camera.global_position = chase_camera.global_position.lerp(target_cam_pos, position_smooth_speed * delta)

	var target_basis = _compute_look_basis(chase_camera.global_position, look_target, Vector3.UP)
	var cur_rot = chase_camera.global_transform.basis.orthonormalized()
	if not cur_rot.is_finite():
		cur_rot = target_basis
	chase_camera.global_transform.basis = cur_rot.slerp(target_basis, rotation_smooth_speed * delta).orthonormalized()

func _update_orbit_camera(delta: float) -> void:
	if not chase_camera or not target_drone:
		return
	orbit_angle += deg_to_rad(25.0) * delta
	var drone_pos = target_drone.global_position
	if not drone_pos.is_finite():
		return
	var offset = Vector3(sin(orbit_angle) * chase_distance, chase_height * 1.2, cos(orbit_angle) * chase_distance)
	chase_camera.global_position = drone_pos + offset
	chase_camera.global_transform.basis = _compute_look_basis(chase_camera.global_position, drone_pos, Vector3.UP)

func _update_top_down_camera(delta: float) -> void:
	if not chase_camera or not target_drone:
		return
	var drone_pos = target_drone.global_position
	if not drone_pos.is_finite():
		return
	var target_pos = drone_pos + Vector3(0.0, 7.5, 0.0)
	chase_camera.global_position = chase_camera.global_position.lerp(target_pos, position_smooth_speed * delta)
	chase_camera.global_transform.basis = _compute_look_basis(chase_camera.global_position, drone_pos, Vector3.FORWARD)
