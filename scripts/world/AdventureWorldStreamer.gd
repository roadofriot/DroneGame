class_name AdventureWorldStreamer
extends Node3D

## AdventureWorldStreamer: Biome-aware continuous 3D open-world terrain streamer.
## Generates connected geographical transitions across Nepal (Cities -> Hills ->
## Valleys -> Rivers -> Glaciers -> Everest Summit) with multi-LOD chunks and
## authentic landmark structures.

const NepalRegions = preload("res://scripts/world/NepalWorldRegions.gd")
const LandmarkBeacon = preload("res://scripts/world/LandmarkBeacon.gd")
const CollectibleCoinScene = preload("res://scenes/collectibles/CollectibleCoin.tscn")

@export var chunk_size: float = 256.0
@export var load_radius: int = 3
@export var unload_radius: int = 4
@export var tracked_target: Node3D = null

var noise: FastNoiseLite = null
var active_chunks: Dictionary = {}
var spawned_landmarks: Dictionary = {}
var spawned_landing_pads: Dictionary = {}

# Biome Materials cache
var biome_materials: Dictionary = {}

# Thread & upload throttling
var _mutex: Mutex = null
var _pending_build: Array[Vector2i] = []
var _building_set: Dictionary = {}
var _completed_queue: Array[Dictionary] = []

func _init() -> void:
	_mutex = Mutex.new()
	_init_noise()
	_init_biome_materials()

func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android"):
		load_radius = 2
		unload_radius = 3

	if not tracked_target:
		tracked_target = get_node_or_null("../Quadcopter")
	if not tracked_target:
		tracked_target = get_node_or_null("../Drone")

	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		if wo.has_signal("origin_shifted"):
			wo.origin_shifted.connect(_on_world_origin_shifted)

	_spawn_all_stage_landmarks()

func _init_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 108
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.frequency = 0.002

func _init_biome_materials() -> void:
	var biomes = [
		{"name": "urban_city", "color": Color(0.32, 0.35, 0.34), "rough": 0.85},
		{"name": "sacred_gardens", "color": Color(0.24, 0.46, 0.22), "rough": 0.8},
		{"name": "mountain_hills", "color": Color(0.36, 0.40, 0.26), "rough": 0.9},
		{"name": "lake_valley", "color": Color(0.22, 0.38, 0.32), "rough": 0.75},
		{"name": "subtropical_forest", "color": Color(0.20, 0.42, 0.18), "rough": 0.85},
		{"name": "ancient_urban", "color": Color(0.40, 0.34, 0.26), "rough": 0.9},
		{"name": "alpine_glacier", "color": Color(0.62, 0.68, 0.75), "rough": 0.5},
		{"name": "everest_summit", "color": Color(0.92, 0.94, 0.98), "rough": 0.35},
		{"name": "alpine_basin", "color": Color(0.72, 0.78, 0.86), "rough": 0.45},
		{"name": "canyon_desert", "color": Color(0.78, 0.52, 0.38), "rough": 0.9}
	]
	for b in biomes:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = b["color"]
		mat.roughness = b["rough"]
		biome_materials[b["name"]] = mat

## Computes continuous geographical elevation taking regional topography into account.
func get_height_at(world_x: float, world_z: float) -> float:
	var base_val = (noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5 # 0.0 .. 1.0
	var reg = NepalRegions.get_region_at_coordinates(Vector3(world_x, 0, world_z))
	var biome = reg.get("biome", "urban_city")
	var target_coord = reg.get("target_coordinates", Vector3.ZERO)
	var dist_to_center = Vector2(world_x - target_coord.x, world_z - target_coord.z).length()

	match biome:
		"urban_city":
			# Gentle valley floor around Butwal (0 to 18m)
			return base_val * 16.0 + 2.0
		"sacred_gardens":
			# Flat serene Lumbini plains (4 to 10m)
			var pond_dist = Vector2(world_x - 500.0, world_z - 3000.0).length()
			if pond_dist < 45.0:
				return 4.0 # Sacred pond depression
			return base_val * 6.0 + 4.0
		"mountain_hills":
			# Steep terraced hills of Palpa/Tansen (90 to 180m)
			return 90.0 + base_val * 85.0
		"lake_valley":
			# Phewa Lake basin (40 to 65m)
			var lake_dist = Vector2(world_x - (-2000.0), world_z - (-7000.0)).length()
			if lake_dist < 280.0:
				return 43.0 # Lake bed
			return 45.0 + base_val * 40.0
		"subtropical_forest":
			# Rolling Terai riverbed of Chitwan (15 to 35m)
			return 15.0 + base_val * 18.0
		"ancient_urban":
			# High plateau of Kathmandu valley (130 to 165m)
			return 130.0 + base_val * 32.0
		"alpine_glacier":
			# Mountain passes and rocky crags (300 to 450m)
			return 300.0 + base_val * 150.0
		"everest_summit":
			# High Sagarmatha ridgelines and summit (580 to 880m)
			return 580.0 + base_val * 280.0
		"alpine_basin":
			# High glacial amphitheater of Annapurna (420 to 580m)
			return 420.0 + base_val * 160.0
		"canyon_desert":
			# Arid high desert plateau of Mustang (350 to 460m)
			return 350.0 + base_val * 110.0
		_:
			return base_val * 30.0

func _physics_process(_delta: float) -> void:
	if not tracked_target or not is_instance_valid(tracked_target):
		return

	var is_ready = tracked_target.is_inside_tree() and tracked_target.is_node_ready()
	var pos = tracked_target.global_position if is_ready else tracked_target.position

	# Calculate current chunk coordinate
	var cur_chunk = Vector2i(
		int(floor(pos.x / chunk_size)),
		int(floor(pos.z / chunk_size))
	)
	_update_streaming_grid(cur_chunk)
	_process_uploads()

func _update_streaming_grid(center: Vector2i) -> void:
	# 1. Enqueue chunks within load_radius
	for dx in range(-load_radius, load_radius + 1):
		for dz in range(-load_radius, load_radius + 1):
			var dist = max(abs(dx), abs(dz))
			if dist <= load_radius:
				var coord = center + Vector2i(dx, dz)
				var desired_lod = 0 if dist <= 1 else 1
				if not active_chunks.has(coord) and not _building_set.has(coord):
					_enqueue_chunk_build(coord, desired_lod)

	# 2. Unload chunks outside unload_radius
	var to_remove: Array[Vector2i] = []
	for c in active_chunks.keys():
		var dx = abs(c.x - center.x)
		var dz = abs(c.y - center.y)
		if max(dx, dz) > unload_radius:
			to_remove.append(c)

	for c in to_remove:
		_unload_chunk(c)

func _enqueue_chunk_build(coord: Vector2i, lod: int) -> void:
	_building_set[coord] = true
	var arrays = _generate_chunk_arrays(coord, lod)
	_completed_queue.append({
		"coord": coord,
		"lod": lod,
		"arrays": arrays
	})

func _generate_chunk_arrays(coord: Vector2i, lod: int) -> Array:
	var step = 16 if lod == 0 else 8
	var cell_size = chunk_size / float(step)
	var origin_x = float(coord.x) * chunk_size
	var origin_z = float(coord.y) * chunk_size

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var vert_count = (step + 1) * (step + 1)
	verts.resize(vert_count)
	norms.resize(vert_count)
	uvs.resize(vert_count)

	var idx = 0
	for iz in range(step + 1):
		var lz = float(iz) * cell_size
		var wz = origin_z + lz
		for ix in range(step + 1):
			var lx = float(ix) * cell_size
			var wx = origin_x + lx
			var wy = get_height_at(wx, wz)

			verts[idx] = Vector3(lx, wy, lz)
			uvs[idx] = Vector2(float(ix) / float(step), float(iz) / float(step))

			# Finite difference normal
			var h_l = get_height_at(wx - 1.0, wz)
			var h_r = get_height_at(wx + 1.0, wz)
			var h_d = get_height_at(wx, wz - 1.0)
			var h_u = get_height_at(wx, wz + 1.0)
			var n = Vector3(h_l - h_r, 2.0, h_d - h_u).normalized()
			norms[idx] = n
			idx += 1

	for iz in range(step):
		for ix in range(step):
			var i0 = iz * (step + 1) + ix
			var i1 = i0 + 1
			var i2 = (iz + 1) * (step + 1) + ix
			var i3 = i2 + 1

			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	return arr

func _process_uploads() -> void:
	if _completed_queue.is_empty():
		return
	var item = _completed_queue.pop_front()
	_instantiate_chunk_mesh(item["coord"], item["lod"], item["arrays"])

func _instantiate_chunk_mesh(coord: Vector2i, lod: int, arrays: Array) -> void:
	_building_set.erase(coord)
	if active_chunks.has(coord):
		var old = active_chunks[coord]
		if is_instance_valid(old["node"]):
			old["node"].queue_free()
		active_chunks.erase(coord)

	var center_x = (float(coord.x) + 0.5) * chunk_size
	var center_z = (float(coord.y) + 0.5) * chunk_size
	var reg = NepalRegions.get_region_at_coordinates(Vector3(center_x, 0, center_z))
	var biome_name = reg.get("biome", "urban_city")
	var mat = biome_materials.get(biome_name, biome_materials["urban_city"])

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, mat)

	var chunk_root = Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]

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
	mesh_inst.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lod > 0
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	chunk_root.add_child(mesh_inst)

	# Static collision on LOD 0
	if lod == 0:
		var sb = StaticBody3D.new()
		sb.collision_layer = 1 | 2
		sb.collision_mask = 1
		var cs = CollisionShape3D.new()
		cs.shape = arr_mesh.create_trimesh_shape()
		sb.add_child(cs)
		chunk_root.add_child(sb)

		# Add regional foliage/props
		var props = _create_biome_props(coord, biome_name)
		if props:
			chunk_root.add_child(props)

	add_child(chunk_root)
	active_chunks[coord] = {
		"node": chunk_root,
		"lod": lod
	}

func _create_biome_props(coord: Vector2i, biome: String) -> Node3D:
	var container = Node3D.new()
	container.name = "Props"
	var rng = RandomNumberGenerator.new()
	rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663) ^ 42

	var count = 10
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count

	match biome:
		"urban_city", "ancient_urban":
			# Commercial/residential buildings
			var box = BoxMesh.new()
			box.size = Vector3(14.0, 24.0, 14.0)
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.45, 0.48, 0.52)
			box.material = b_mat
			mm.mesh = box
		"sacred_gardens", "subtropical_forest":
			# Lush trees
			var cone = CylinderMesh.new()
			cone.top_radius = 0.2
			cone.bottom_radius = 3.0
			cone.height = 8.0
			var t_mat = StandardMaterial3D.new()
			t_mat.albedo_color = Color(0.15, 0.38, 0.18)
			cone.material = t_mat
			mm.mesh = cone
		"alpine_glacier", "everest_summit":
			# Boulders and ice crags
			var rock = BoxMesh.new()
			rock.size = Vector3(8.0, 12.0, 8.0)
			var r_mat = StandardMaterial3D.new()
			r_mat.albedo_color = Color(0.85, 0.88, 0.95)
			rock.material = r_mat
			mm.mesh = rock
		_:
			# Default hills pine
			var pine = CylinderMesh.new()
			pine.top_radius = 0.1
			pine.bottom_radius = 2.2
			pine.height = 7.0
			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.18, 0.32, 0.16)
			pine.material = p_mat
			mm.mesh = pine

	for i in range(count):
		var rx = rng.randf_range(20.0, chunk_size - 20.0)
		var rz = rng.randf_range(20.0, chunk_size - 20.0)
		var wx = float(coord.x) * chunk_size + rx
		var wz = float(coord.y) * chunk_size + rz
		var wy = get_height_at(wx, wz)

		var sc = rng.randf_range(0.8, 1.3)
		var t = Transform3D()
		t = t.scaled(Vector3(sc, sc, sc))
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t.origin = Vector3(rx, wy + 4.0 * sc, rz)
		mm.set_instance_transform(i, t)

	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.multimesh = mm
	container.add_child(mm_inst)
	return container

func _unload_chunk(coord: Vector2i) -> void:
	if active_chunks.has(coord):
		var ch = active_chunks[coord]
		if is_instance_valid(ch["node"]):
			ch["node"].queue_free()
		active_chunks.erase(coord)

## Spawns distinct 3D landmark structures for each of the 8 Nepal stages.
func _spawn_all_stage_landmarks() -> void:
	var stages = NepalRegions.get_all_stages()
	for st in stages:
		_spawn_stage_landing_pad(st)
		for lm in st.get("landmarks", []):
			_spawn_landmark_structure(lm)

func _spawn_stage_landing_pad(stage_def: Dictionary) -> void:
	var pad_pos: Vector3 = stage_def.get("landing_pad_position", Vector3.ZERO)
	var terrain_h = get_height_at(pad_pos.x, pad_pos.z)
	pad_pos.y = terrain_h + 0.2

	var pad_root = StaticBody3D.new()
	pad_root.name = "Pad_" + stage_def.get("id", "stage")
	pad_root.collision_layer = 1 | 2
	pad_root.collision_mask = 0

	# Base circular pad
	var pad_mesh = CylinderMesh.new()
	pad_mesh.top_radius = 6.0
	pad_mesh.bottom_radius = 6.0
	pad_mesh.height = 0.4
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.28)
	pad_mesh.material = mat

	var pad_inst = MeshInstance3D.new()
	pad_inst.mesh = pad_mesh
	pad_root.add_child(pad_inst)

	# Static collision collider for drone resting and raycast sensing
	var pad_col = CollisionShape3D.new()
	var pad_cyl = CylinderShape3D.new()
	pad_cyl.radius = 6.0
	pad_cyl.height = 0.4
	pad_col.shape = pad_cyl
	pad_root.add_child(pad_col)

	# Luminous landing ring
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 5.2
	ring_mesh.outer_radius = 5.8
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.85, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.85, 1.0)
	ring_mat.emission_energy_multiplier = 3.0
	ring_mesh.material = ring_mat

	var ring_inst = MeshInstance3D.new()
	ring_inst.mesh = ring_mesh
	ring_inst.position = Vector3(0.0, 0.25, 0.0)
	pad_root.add_child(ring_inst)

	# Vertical landing zone light guide (Sky beacon)
	var beam = CylinderMesh.new()
	beam.top_radius = 2.0
	beam.bottom_radius = 1.0
	beam.height = 200.0
	var b_mat = StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.35)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.2, 0.9, 1.0)
	b_mat.emission_energy_multiplier = 4.0
	beam.material = b_mat

	var beam_inst = MeshInstance3D.new()
	beam_inst.mesh = beam
	beam_inst.position = Vector3(0.0, 100.0, 0.0)
	pad_root.add_child(beam_inst)

	pad_root.position = pad_pos
	add_child(pad_root)
	spawned_landing_pads[stage_def.get("id")] = pad_root

func _spawn_landmark_structure(lm_def: Dictionary) -> void:
	var lm_pos: Vector3 = lm_def.get("position", Vector3.ZERO)
	var lm_root = Node3D.new()
	lm_root.name = "Landmark_" + lm_def.get("id", "lm")

	# Characteristic monument/beacon marker
	var tower = BoxMesh.new()
	tower.size = Vector3(5.0, 22.0, 5.0)
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.85, 0.55, 0.2)
	tower.material = t_mat

	var tower_inst = MeshInstance3D.new()
	tower_inst.mesh = tower
	tower_inst.position = Vector3(0.0, 11.0, 0.0)
	lm_root.add_child(tower_inst)

	# Glowing beacon gem
	var gem = SphereMesh.new()
	gem.radius = 2.0
	gem.height = 4.0
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(1.0, 0.8, 0.2)
	g_mat.emission_enabled = true
	g_mat.emission = Color(1.0, 0.8, 0.2)
	g_mat.emission_energy_multiplier = 4.0
	gem.material = g_mat

	var gem_inst = MeshInstance3D.new()
	gem_inst.mesh = gem
	gem_inst.position = Vector3(0.0, 24.0, 0.0)
	lm_root.add_child(gem_inst)

	lm_root.position = lm_pos
	add_child(lm_root)
	spawned_landmarks[lm_def.get("id")] = lm_root

func _on_world_origin_shifted(shift_vector: Vector3, _accum: Vector3) -> void:
	for ch in active_chunks.values():
		if is_instance_valid(ch["node"]):
			ch["node"].position -= shift_vector
	for pad in spawned_landing_pads.values():
		if is_instance_valid(pad):
			pad.position -= shift_vector
	for lm in spawned_landmarks.values():
		if is_instance_valid(lm):
			lm.position -= shift_vector
