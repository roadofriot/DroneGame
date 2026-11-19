class_name TerrainStreamer
extends Node3D

const ChunkProps = preload("res://scripts/world/ChunkProps.gd")
const LandmarkBeacon = preload("res://scripts/world/LandmarkBeacon.gd")

## TerrainStreamer: Multi-threaded procedural infinite terrain streamer (Phase 9).
## Features:
## - 256 m x 256 m chunks generated using FastNoiseLite
## - Multi-threaded vertex computation on WorkerThreadPool
## - Per-frame upload budget throttle (eliminates micro-stutter)
## - 2 LOD levels: LOD0 (32x32) within 2 chunks, LOD1 (16x16) beyond
## - Dynamic HeightMapShape3D collision enabled ONLY within 1 chunk of drone
## - Chunk unload with hysteresis (unload_radius = load_radius + 1)
## - Seamless floating origin compatibility via WorldOrigin

@export var chunk_size: float = 256.0
@export var load_radius: int = 4
@export var unload_radius: int = 5
@export var max_height: float = 85.0
@export var noise_seed: int = 42
@export var upload_budget_per_frame: int = 1
@export var enable_threading: bool = true
@export var tracked_target: Node3D = null

# Core Noise Generator
var noise: FastNoiseLite = null

# Active chunks: Vector2i(chunk_x, chunk_z) -> ChunkData dictionary
var active_chunks: Dictionary = {}

# Thread Synchronization
var _mutex: Mutex = null
var _pending_build: Array[Vector2i] = []
var _building_set: Dictionary = {}
var _completed_queue: Array[Dictionary] = []

# Terrain Material (Procedural PBR)
var terrain_material: StandardMaterial3D = null

# Beacon registry to avoid duplicates
var active_beacons: Dictionary = {}

func _init() -> void:
	_mutex = Mutex.new()
	_init_noise()
	_init_material()

func _ready() -> void:
	if not tracked_target:
		tracked_target = get_node_or_null("../Quadcopter")
	if not tracked_target:
		tracked_target = get_node_or_null("../Drone")

	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		if wo.has_signal("origin_shifted"):
			wo.origin_shifted.connect(_on_world_origin_shifted)

func _init_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.frequency = 0.0035

func _init_material() -> void:
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(0.24, 0.38, 0.22) # Alpine green/moss
	terrain_material.roughness = 0.88
	terrain_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

static func sample_height(n: FastNoiseLite, h_max: float, world_x: float, world_z: float) -> float:
	if not n:
		return 0.0
	return n.get_noise_2d(world_x, world_z) * h_max

func get_height_at(world_x: float, world_z: float) -> float:
	return sample_height(noise, max_height, world_x, world_z)

func _process(_delta: float) -> void:
	_process_uploads()
	_update_streaming_grid()

func _update_streaming_grid() -> void:
	if not tracked_target or not is_instance_valid(tracked_target):
		return

	# Determine current true world chunk coordinates
	var player_pos = tracked_target.global_position if (tracked_target.is_inside_tree() and tracked_target.is_node_ready()) else tracked_target.position
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		player_pos = wo.to_true_world(player_pos)

	var cur_cx = int(floor(player_pos.x / chunk_size))
	var cur_cz = int(floor(player_pos.z / chunk_size))
	var cur_coord = Vector2i(cur_cx, cur_cz)

	# 1. Unload distant chunks (hysteresis buffer)
	var coords_to_remove: Array[Vector2i] = []
	for coord in active_chunks.keys():
		var dist = _chebyshev_distance(coord, cur_coord)
		if dist > unload_radius:
			coords_to_remove.append(coord)

	for c in coords_to_remove:
		_unload_chunk(c)

	# 2. Queue missing chunks within load_radius
	for x in range(cur_cx - load_radius, cur_cx + load_radius + 1):
		for z in range(cur_cz - load_radius, cur_cz + load_radius + 1):
			var c = Vector2i(x, z)
			if _chebyshev_distance(c, cur_coord) <= load_radius:
				var desired_lod = 0 if _chebyshev_distance(c, cur_coord) <= 2 else 1
				if not active_chunks.has(c) and not _building_set.has(c):
					_queue_chunk_generation(c, desired_lod)
				elif active_chunks.has(c):
					# Check if LOD upgrade is needed (e.g. player flew closer)
					var ch_data = active_chunks[c]
					if ch_data["lod"] > desired_lod and not _building_set.has(c):
						_queue_chunk_generation(c, desired_lod)

	# 3. Update collision gating: Only chunks within distance 1 have active colliders
	for coord in active_chunks.keys():
		var ch = active_chunks[coord]
		var dist = _chebyshev_distance(coord, cur_coord)
		var col_body = ch.get("body", null)
		if col_body and is_instance_valid(col_body):
			var should_collide = (dist <= 1)
			if col_body.collision_layer != (2 if should_collide else 0):
				col_body.collision_layer = 2 if should_collide else 0
				col_body.collision_mask = 1 if should_collide else 0

func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _queue_chunk_generation(coord: Vector2i, lod: int) -> void:
	_building_set[coord] = true
	if enable_threading:
		WorkerThreadPool.add_task(_generate_chunk_threaded.bind(coord, lod, noise, max_height, chunk_size))
	else:
		_generate_chunk_threaded(coord, lod, noise, max_height, chunk_size)

func _generate_chunk_threaded(coord: Vector2i, lod: int, n: FastNoiseLite, h_max: float, c_size: float) -> void:
	var res = 32 if lod == 0 else 16
	var step = c_size / float(res)

	var origin_x = float(coord.x) * c_size
	var origin_z = float(coord.y) * c_size

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var vert_count = (res + 1) * (res + 1)
	vertices.resize(vert_count)
	normals.resize(vert_count)
	uvs.resize(vert_count)

	# Generate Vertices & Heights
	var idx = 0
	for gz in range(res + 1):
		for gx in range(res + 1):
			var wx = origin_x + float(gx) * step
			var wz = origin_z + float(gz) * step
			var wy = (n.get_noise_2d(wx, wz) * h_max) if n else 0.0

			# Vertex position local to chunk origin
			vertices[idx] = Vector3(float(gx) * step, wy, float(gz) * step)
			uvs[idx] = Vector2(float(gx) / float(res), float(gz) / float(res))
			idx += 1

	# Calculate Normals using central differences
	for gz in range(res + 1):
		for gx in range(res + 1):
			var i = gz * (res + 1) + gx
			var wx = origin_x + float(gx) * step
			var wz = origin_z + float(gz) * step

			var h_l = (n.get_noise_2d(wx - 2.0, wz) * h_max) if n else 0.0
			var h_r = (n.get_noise_2d(wx + 2.0, wz) * h_max) if n else 0.0
			var h_d = (n.get_noise_2d(wx, wz - 2.0) * h_max) if n else 0.0
			var h_u = (n.get_noise_2d(wx, wz + 2.0) * h_max) if n else 0.0

			var norm = Vector3(h_l - h_r, 4.0, h_d - h_u).normalized()
			normals[i] = norm

	# Generate Indices
	for gz in range(res):
		for gx in range(res):
			var top_l = gz * (res + 1) + gx
			var top_r = top_l + 1
			var bot_l = (gz + 1) * (res + 1) + gx
			var bot_r = bot_l + 1

			indices.append(top_l)
			indices.append(bot_l)
			indices.append(top_r)

			indices.append(top_r)
			indices.append(bot_l)
			indices.append(bot_r)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	_mutex.lock()
	_completed_queue.append({
		"coord": coord,
		"lod": lod,
		"arrays": arrays
	})
	_mutex.unlock()

func _process_uploads() -> void:
	var uploads_done = 0
	while uploads_done < upload_budget_per_frame:
		_mutex.lock()
		if _completed_queue.is_empty():
			_mutex.unlock()
			break
		var item = _completed_queue.pop_front()
		_mutex.unlock()

		_instantiate_chunk_mesh(item["coord"], item["lod"], item["arrays"])
		uploads_done += 1

func _instantiate_chunk_mesh(coord: Vector2i, lod: int, arrays: Array) -> void:
	_building_set.erase(coord)

	# If chunk already exists with same or higher LOD, replace it
	if active_chunks.has(coord):
		var old = active_chunks[coord]
		if is_instance_valid(old["node"]):
			old["node"].queue_free()
		active_chunks.erase(coord)

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, terrain_material)

	var chunk_root = Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]

	# Position in local world coordinates
	var local_x = float(coord.x) * chunk_size
	var local_z = float(coord.y) * chunk_size
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		var loc = wo.to_local(Vector3(local_x, 0, local_z))
		local_x = loc.x
		local_z = loc.z

	chunk_root.position = Vector3(local_x, 0, local_z)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = arr_mesh
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lod > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk_root.add_child(mesh_inst)

	# Collision Body (Layer 2 = terrain)
	var static_body = StaticBody3D.new()
	static_body.collision_layer = 2
	static_body.collision_mask = 1
	var col_shape = CollisionShape3D.new()
	col_shape.shape = arr_mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	chunk_root.add_child(static_body)

	# Add deterministic foliage for high-detail near chunks (LOD 0)
	if lod == 0:
		var foliage = ChunkProps.create_chunk_foliage(coord, chunk_size, self)
		chunk_root.add_child(foliage)

	add_child(chunk_root)

	active_chunks[coord] = {
		"node": chunk_root,
		"body": static_body,
		"lod": lod
	}

	# Spawn landmark beacon if this chunk contains a 1000m grid intersection
	_check_and_spawn_beacon(coord)

func _check_and_spawn_beacon(coord: Vector2i) -> void:
	var chunk_min_x = coord.x * int(chunk_size)
	var chunk_max_x = (coord.x + 1) * int(chunk_size)
	var chunk_min_z = coord.y * int(chunk_size)
	var chunk_max_z = (coord.y + 1) * int(chunk_size)

	# Find 1000m mark inside this chunk
	var b_x = int(ceil(float(chunk_min_x) / 1000.0)) * 1000
	var b_z = int(ceil(float(chunk_min_z) / 1000.0)) * 1000

	if b_x >= chunk_min_x and b_x < chunk_max_x and b_z >= chunk_min_z and b_z < chunk_max_z:
		var beacon_key = Vector2i(b_x / 1000, b_z / 1000)
		if not active_beacons.has(beacon_key):
			_spawn_landmark_beacon(beacon_key, float(b_x), float(b_z))

func _spawn_landmark_beacon(key: Vector2i, wx: float, wz: float) -> void:
	var wy = get_height_at(wx, wz)
	var beacon = LandmarkBeacon.new(key, Vector3(wx, wy, wz))
	add_child(beacon)
	active_beacons[key] = beacon

func _unload_chunk(coord: Vector2i) -> void:
	if active_chunks.has(coord):
		var ch = active_chunks[coord]
		if is_instance_valid(ch["node"]):
			ch["node"].queue_free()
		active_chunks.erase(coord)

func _on_world_origin_shifted(shift_vector: Vector3, _accum_offset: Vector3) -> void:
	# Shift local positions of all active chunks and beacons
	for ch in active_chunks.values():
		if is_instance_valid(ch["node"]):
			ch["node"].position -= shift_vector

	for beacon in active_beacons.values():
		if is_instance_valid(beacon):
			beacon.position -= shift_vector
