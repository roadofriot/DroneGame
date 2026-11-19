class_name WorldOriginAutoload
extends Node

## WorldOrigin: Floating Origin & 64-bit True World Coordinate Manager (Phase 9).
## Prevents IEEE-754 32-bit floating point precision loss and jitter over 20+ km flights.
## When the drone flies > 2000 m from the local origin, an origin shift is staged.
## Shifts are applied cleanly inside _integrate_forces for RigidBody3D to avoid velocity spikes.

signal origin_shifted(shift_vector: Vector3, accumulated_offset: Vector3)

# 64-bit float cumulative world offset from initial spawn (0, 0, 0)
var global_world_offset: Vector3 = Vector3.ZERO

# Shift distance threshold in meters (default 2000.0m)
var shift_threshold: float = 2000.0

# Chunk alignment grid size (256m matches TerrainStreamer chunk size)
var chunk_alignment: float = 256.0

# Pending shift state for physics synchronization
var pending_shift: Vector3 = Vector3.ZERO
var is_shift_pending: bool = false

# Subscribed player drone reference
var tracked_drone: Node3D = null

func _ready() -> void:
	process_physics_priority = -100 # Run before gameplay and physics bodies

func register_drone(drone: Node3D) -> void:
	tracked_drone = drone

func unregister_drone(drone: Node3D) -> void:
	if tracked_drone == drone:
		tracked_drone = null

func reset() -> void:
	global_world_offset = Vector3.ZERO
	pending_shift = Vector3.ZERO
	is_shift_pending = false

func _physics_process(delta: float) -> void:
	check_origin_shift(delta)

## Checks drone position and stages an origin shift if distance threshold is exceeded.
func check_origin_shift(_delta: float = 0.0) -> void:
	if not tracked_drone or not is_instance_valid(tracked_drone):
		return

	var is_ready_in_tree = tracked_drone.is_inside_tree() and tracked_drone.is_node_ready()
	var cur_pos = tracked_drone.global_position if is_ready_in_tree else tracked_drone.position
	var dist_horizontal = Vector2(cur_pos.x, cur_pos.z).length()

	if dist_horizontal > shift_threshold and not is_shift_pending:
		# Calculate chunk-aligned shift vector to avoid fractional vertex re-interpolation
		var shift_x = roundf(cur_pos.x / chunk_alignment) * chunk_alignment
		var shift_z = roundf(cur_pos.z / chunk_alignment) * chunk_alignment
		var shift_vec = Vector3(shift_x, 0.0, shift_z)
		trigger_shift(shift_vec)

## Triggers an origin shift of magnitude shift_vector.
## Staged for execution by physics direct body state and scene nodes.
func trigger_shift(shift_vec: Vector3) -> void:
	if shift_vec.is_zero_approx():
		return

	pending_shift = shift_vec
	is_shift_pending = true
	global_world_offset += shift_vec

	# Emit signal to all registered non-physics world nodes (terrain, sky, props, camera)
	origin_shifted.emit(shift_vec, global_world_offset)

## Consumed by tracked RigidBody3D inside _integrate_forces to safely reposition without impulse.
func consume_physics_shift() -> Vector3:
	if not is_shift_pending:
		return Vector3.ZERO
	var s = pending_shift
	pending_shift = Vector3.ZERO
	is_shift_pending = false
	return s

# -----------------------------------------------------------------------------
# Coordinate Conversions (64-Bit Float Precision)
# -----------------------------------------------------------------------------
## Converts local scene coordinates to absolute true world coordinates.
func to_true_world(local_pos: Vector3) -> Vector3:
	return local_pos + global_world_offset

## Converts absolute true world coordinates to current local scene coordinates.
func to_local(true_world_pos: Vector3) -> Vector3:
	return true_world_pos - global_world_offset

## Calculates distance between two local positions accounting for world origin.
func get_distance(local_pos_a: Vector3, local_pos_b: Vector3) -> float:
	return local_pos_a.distance_to(local_pos_b)

## Calculates distance from a local position to a true world position.
func get_distance_to_true(local_pos: Vector3, true_world_target: Vector3) -> float:
	var local_target = to_local(true_world_target)
	return local_pos.distance_to(local_target)
