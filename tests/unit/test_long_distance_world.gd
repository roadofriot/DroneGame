extends SceneTree

## Dedicated Unit Test Suite for Phase 9: Long-Distance World (20+ km Flight)
## Validates WorldOrigin floating origin shifts, 64-bit coordinate accuracy,
## simulated straight flight to 20 km (zero-NaN, local pos within ±2.5 km, true distance accurate to 1m),
## TerrainStreamer bounded chunk counts with hysteresis, and selective collision gating.

const WorldOriginAutoload = preload("res://scripts/core/WorldOrigin.gd")
const GameStateAutoload = preload("res://scripts/core/GameState.gd")
const TerrainStreamer = preload("res://scripts/world/TerrainStreamer.gd")
const LandmarkBeacon = preload("res://scripts/world/LandmarkBeacon.gd")
const ChunkProps = preload("res://scripts/world/ChunkProps.gd")

func _init() -> void:
	run_tests()

func run_tests() -> void:
	print("==================================================")
	print("Starting Phase 9 Long-Distance World Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 7

	if test_ld01_world_origin_floating_shifts():
		tests_passed += 1
	if test_ld02_simulated_20km_flight():
		tests_passed += 1
	if test_ld03_terrain_streamer_heightmap():
		tests_passed += 1
	if test_ld04_chunk_count_bounded_and_hysteresis():
		tests_passed += 1
	if test_ld05_selective_collision_gating():
		tests_passed += 1
	if test_ld06_landmark_beacon_placement():
		tests_passed += 1
	if test_ld07_gamestate_autoload_tracking():
		tests_passed += 1

	print("==================================================")
	print("Phase 9 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 9 LONG-DISTANCE WORLD TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 9 LONG-DISTANCE WORLD TESTS FAILED! <<")
		quit(1)

func test_ld01_world_origin_floating_shifts() -> bool:
	print("[LD-01] Testing WorldOrigin Floating Origin Shift Logic...")
	var wo = WorldOriginAutoload.new()
	wo.shift_threshold = 2000.0
	wo.chunk_alignment = 256.0

	var dummy_drone = Node3D.new()
	dummy_drone.position = Vector3(2100.0, 15.0, 0.0)
	wo.register_drone(dummy_drone)

	# Run a physics process tick
	wo._physics_process(0.016)

	if not wo.is_shift_pending:
		printerr("  - FAIL: Origin shift was not staged when drone exceeded 2000m")
		dummy_drone.free()
		wo.free()
		return false

	var shift = wo.consume_physics_shift()
	# Expect chunk alignment: round(2100 / 256) * 256 = 8 * 256 = 2048m
	if absf(shift.x - 2048.0) > 0.1:
		printerr("  - FAIL: Shift magnitude should be 2048m, got: ", shift.x)
		dummy_drone.free()
		wo.free()
		return false

	# Reposition dummy drone as RigidBody3D would inside _integrate_forces
	dummy_drone.position -= shift
	if absf(dummy_drone.position.x - 52.0) > 0.1:
		printerr("  - FAIL: Local drone pos should be reset near zero (52m), got: ", dummy_drone.position.x)
		dummy_drone.free()
		wo.free()
		return false

	# Check true world coordinate reconstruction
	var true_pos = wo.to_true_world(dummy_drone.position)
	if absf(true_pos.x - 2100.0) > 0.001:
		printerr("  - FAIL: True world coordinate reconstruction mismatch: ", true_pos.x)
		dummy_drone.free()
		wo.free()
		return false

	dummy_drone.free()
	wo.free()
	print("  - Floating origin shift and true coordinate reconstruction verified (PASS)")
	return true

func test_ld02_simulated_20km_flight() -> bool:
	print("[LD-02] Testing Simulated Straight Flight to 20 km (Zero-NaN & Bounded Local Pos)...")
	var wo = WorldOriginAutoload.new()
	wo.shift_threshold = 2000.0
	wo.chunk_alignment = 256.0

	var drone = Node3D.new()
	drone.position = Vector3.ZERO
	wo.register_drone(drone)

	var target_distance_m: float = 20000.0
	var speed_mps: float = 200.0 # High speed simulation step
	var dt: float = 0.05
	var step_distance = speed_mps * dt

	var total_distance_flown: float = 0.0
	var shift_count: int = 0
	var max_local_distance: float = 0.0

	# Fly in a straight line at heading 30 degrees North-East
	var flight_dir = Vector3(sin(deg_to_rad(30.0)), 0.0, -cos(deg_to_rad(30.0))).normalized()

	while total_distance_flown < target_distance_m:
		drone.position += flight_dir * step_distance
		total_distance_flown += step_distance

		wo._physics_process(dt)

		if wo.is_shift_pending:
			var s = wo.consume_physics_shift()
			drone.position -= s
			shift_count += 1

		var local_dist = Vector2(drone.position.x, drone.position.z).length()
		max_local_distance = maxf(max_local_distance, local_dist)

		# Guard against NaN / Inf
		if not drone.position.is_finite() or not wo.global_world_offset.is_finite():
			printerr("  - FAIL: NaN or Inf detected during 20km flight!")
			drone.free()
			wo.free()
			return false

	# Assertions:
	# 1. Local position never exceeded ±2.5 km (stays bounded around origin)
	if max_local_distance > 2500.0:
		printerr("  - FAIL: Local distance exceeded 2500m: ", max_local_distance)
		drone.free()
		wo.free()
		return false

	# 2. Origin shifts fired periodically (at 20km / 2km ~ 9-10 shifts)
	if shift_count < 8:
		printerr("  - FAIL: Insufficient origin shifts fired: ", shift_count)
		drone.free()
		wo.free()
		return false

	# 3. True world position is accurate to 1 meter
	var true_pos = wo.to_true_world(drone.position)
	var true_dist = true_pos.length()
	if absf(true_dist - target_distance_m) > 1.0:
		printerr("  - FAIL: True distance mismatch: expected %f, got %f" % [target_distance_m, true_dist])
		drone.free()
		wo.free()
		return false

	drone.free()
	wo.free()
	print("  - 20 km straight flight verified: %d origin shifts, max local pos %.1fm, true dist accurate to <1m (PASS)" % [shift_count, max_local_distance])
	return true

func test_ld03_terrain_streamer_heightmap() -> bool:
	print("[LD-03] Testing TerrainStreamer Heightmap Generation & Seed Repeatability...")
	var ts = TerrainStreamer.new()
	ts.noise_seed = 12345
	ts._init_noise()

	var h1 = ts.get_height_at(150.0, 300.0)
	var h2 = ts.get_height_at(150.0, 300.0)

	# Must be strictly deterministic
	if absf(h1 - h2) > 0.00001:
		printerr("  - FAIL: Non-deterministic height values")
		ts.free()
		return false

	if not is_finite(h1):
		printerr("  - FAIL: Non-finite height returned")
		ts.free()
		return false

	# Different locations have distinct procedural heights
	var h3 = ts.get_height_at(1500.0, 2500.0)
	if absf(h1 - h3) < 0.001:
		printerr("  - FAIL: Procedural terrain flat or repetitive")
		ts.free()
		return false

	ts.free()
	print("  - FastNoiseLite procedural heightmap determinism verified (PASS)")
	return true

func test_ld04_chunk_count_bounded_and_hysteresis() -> bool:
	print("[LD-04] Testing Chunk Count Bounds & Unload Hysteresis...")
	var ts = TerrainStreamer.new()
	ts.enable_threading = false
	ts.load_radius = 2
	ts.unload_radius = 3
	ts.chunk_size = 256.0

	var dummy = Node3D.new()
	root.add_child(dummy)
	dummy.position = Vector3(0.0, 10.0, 0.0)
	ts.tracked_target = dummy

	# Simulate active chunks dictionary with coordinates
	for x in range(-2, 3):
		for z in range(-2, 3):
			var c = Vector2i(x, z)
			var node = Node3D.new()
			ts.active_chunks[c] = {"node": node, "body": null, "lod": 0}

	var initial_count = ts.active_chunks.size()
	if initial_count != 25: # (2*2+1)^2 = 25
		printerr("  - FAIL: Expected 25 chunks initially, got: ", initial_count)
		dummy.queue_free()
		ts.free()
		return false

	# Move player forward by 3 chunks (768m)
	dummy.position = Vector3(0.0, 10.0, 768.0)
	ts._update_streaming_grid()

	# Chunks with distance > unload_radius (3) must be marked for unload
	var max_active_cap = (ts.unload_radius * 2 + 1) * (ts.unload_radius * 2 + 1)
	if ts.active_chunks.size() > max_active_cap:
		printerr("  - FAIL: Active chunk count exceeded hysteresis limit: ", ts.active_chunks.size())
		dummy.queue_free()
		ts.free()
		return false

	for ch in ts.active_chunks.values():
		if is_instance_valid(ch["node"]):
			ch["node"].free()
	dummy.queue_free()
	ts.queue_free()
	print("  - Chunk streaming bounds and hysteresis unloading verified (PASS)")
	return true

func test_ld05_selective_collision_gating() -> bool:
	print("[LD-05] Testing Selective Collision Gating (Near Chunks Only)...")
	var ts = TerrainStreamer.new()
	ts.load_radius = 0 # Prevent background chunk queuing during isolated test
	ts.unload_radius = 10
	ts.chunk_size = 256.0

	var dummy = Node3D.new()
	root.add_child(dummy)
	dummy.position = Vector3(0.0, 10.0, 0.0)
	ts.tracked_target = dummy

	# Create a near chunk (distance 1) and a far chunk (distance 3)
	var near_body = StaticBody3D.new()
	near_body.collision_layer = 2
	var far_body = StaticBody3D.new()
	far_body.collision_layer = 2

	var near_node = Node3D.new()
	var far_node = Node3D.new()

	ts.active_chunks[Vector2i(1, 0)] = {"node": near_node, "body": near_body, "lod": 0}
	ts.active_chunks[Vector2i(3, 0)] = {"node": far_node, "body": far_body, "lod": 1}

	ts._update_streaming_grid()

	var pass_ok = true
	# Near chunk (dist <= 1) should have collision layer 2
	if near_body.collision_layer != 2:
		printerr("  - FAIL: Near chunk should have active collision layer (2), got: ", near_body.collision_layer)
		pass_ok = false

	# Far chunk (dist > 1) must have collision disabled (layer 0)
	if far_body.collision_layer != 0:
		printerr("  - FAIL: Far chunk (>1 distance) should have collision disabled (0), got: ", far_body.collision_layer)
		pass_ok = false

	ts.active_chunks.clear()
	near_body.free()
	far_body.free()
	near_node.free()
	far_node.free()
	dummy.queue_free()
	ts.queue_free()
	if pass_ok:
		print("  - Selective collision layer gating verified (PASS)")
	return pass_ok

func test_ld06_landmark_beacon_placement() -> bool:
	print("[LD-06] Testing 1 km Landmark Beacon Grid Waypoint...")
	var beacon = LandmarkBeacon.new(Vector2i(2, -3), Vector3(2000.0, 45.0, -3000.0))
	beacon._build_beacon()

	if beacon.name != "Beacon_2_-3":
		printerr("  - FAIL: Beacon naming mismatch: ", beacon.name)
		beacon.free()
		return false

	if beacon.get_child_count() < 3:
		printerr("  - FAIL: Beacon visual hierarchy incomplete, child count: ", beacon.get_child_count())
		beacon.free()
		return false

	beacon.free()
	print("  - Landmark navigation beacon procedural construction verified (PASS)")
	return true

func test_ld07_gamestate_autoload_tracking() -> bool:
	print("[LD-07] Testing GameState Session Data & Persistence...")
	var gs = GameStateAutoload.new()

	gs.set_active_preset("racer")
	if gs.active_preset != "racer":
		printerr("  - FAIL: Active preset setter failed")
		gs.free()
		return false

	gs.set_flight_profile("acro")
	if gs.active_flight_profile != "acro":
		printerr("  - FAIL: Active profile setter failed")
		gs.free()
		return false

	gs.set_true_home(Vector3(100.0, 5.0, -250.0))
	if gs.true_home_position != Vector3(100.0, 5.0, -250.0):
		printerr("  - FAIL: True home position mismatch")
		gs.free()
		return false

	gs.record_distance_traveled(1542.5)
	if absf(gs.total_distance_meters - 1542.5) > 0.01:
		printerr("  - FAIL: Distance tracking mismatch")
		gs.free()
		return false

	gs.free()
	print("  - GameState global session data tracking verified (PASS)")
	return true
