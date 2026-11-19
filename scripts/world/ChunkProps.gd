class_name ChunkProps
extends RefCounted

## ChunkProps: Deterministic procedural prop scatterer per 256m terrain chunk (Phase 9).
## Employs MultiMeshInstance3D for low-draw-call foliage (pine trees, boulders).
## PRNG is strictly seeded per chunk coordinate for persistent repeatable placement.

static func create_chunk_foliage(coord: Vector2i, chunk_size: float, streamer: Node) -> Node3D:
	var container = Node3D.new()
	container.name = "Props"

	var rng = RandomNumberGenerator.new()
	# Deterministic seed combining prime hash
	rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663) ^ 42

	# 1. Tree MultiMesh (16 trees per chunk)
	var tree_count = 14
	var mm_tree = MultiMesh.new()
	mm_tree.transform_format = MultiMesh.TRANSFORM_3D
	mm_tree.instance_count = tree_count

	# Procedural pine tree mesh: cone on cylinder
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.1
	cone_mesh.bottom_radius = 2.2
	cone_mesh.height = 7.0
	var tree_mat = StandardMaterial3D.new()
	tree_mat.albedo_color = Color(0.12, 0.28, 0.14)
	tree_mat.roughness = 0.9
	cone_mesh.material = tree_mat
	mm_tree.mesh = cone_mesh

	for i in range(tree_count):
		var rx = rng.randf_range(16.0, chunk_size - 16.0)
		var rz = rng.randf_range(16.0, chunk_size - 16.0)
		var wx = float(coord.x) * chunk_size + rx
		var wz = float(coord.y) * chunk_size + rz
		var wy = streamer.get_height_at(wx, wz)

		var sc = rng.randf_range(0.8, 1.4)
		var rot = rng.randf_range(0.0, TAU)
		var t = Transform3D()
		t = t.scaled(Vector3(sc, sc, sc))
		t = t.rotated(Vector3.UP, rot)
		t.origin = Vector3(rx, wy + 3.5 * sc, rz)
		mm_tree.set_instance_transform(i, t)

	var mm_inst = MultiMeshInstance3D.new()
	mm_inst.multimesh = mm_tree
	container.add_child(mm_inst)

	return container
